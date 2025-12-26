---
applyTo: '**/*.dart'
---

# Tests
- ALWAYS write tests for EVERY publicly accessible class, function, and method.
- ALWAYS write tests with the primary goal of exposing possible bugs — NOT simply making tests pass.
- ALWAYS test failure cases, invalid input, unexpected state, and edge conditions.
- ALWAYS create exactly one unit test file per class being tested.
- ALWAYS name the test file `<class_name>_test.dart` or `<feature_name>_test.dart`.

# Unit Tests
- ALWAYS use Arrange–Act–Assert pattern with clear separation.
- ALWAYS write descriptive test names that explain expected behavior.
- ALWAYS add inline comments inside tests explaining WHY assertions matter.
- ALWAYS include tests for:
  - Happy path behavior
  - Error cases and thrown exceptions
  - Boundary conditions
  - Null / empty values where applicable
  - Timing and concurrency behavior if async
- NEVER skip tests for private methods if they contain complex logic.  
  (If a private method is trivial, call it indirectly through public API instead.)
- WHEN a class depends on collaborators, ALWAYS use fakes or stubs — NEVER use real infrastructure in unit tests.

# Integration Tests (only when applicable)
- ALWAYS write integration tests to verify whole workflows that span multiple public classes.
- ALWAYS cover multi-step flows, IO boundaries, and dependency wiring.
- NEVER write integration tests when a unit test is sufficient.
- ALWAYS isolate integration tests into `test/integration/` and name according to workflow.

# Test Hygiene
- NEVER use random sleeps or timing hacks — use proper async waiting or dependency injection.
- NEVER rely on global order of test execution.
- ALWAYS ensure tests remain readable after years — avoid clever tricks or meta test logic.

# Mocks
- ALWAYS use Mockito for mocking dependencies.
- ALWAYS mock collaborators instead of creating real implementations in unit tests.
- ALWAYS generate mock classes via `build_runner` when needed.
- NEVER use real data sources, HTTP calls, or platform channels in unit tests.
- ALWAYS verify interactions on mocks when behavior depends on method-call side effects.
- ALWAYS keep mock usage minimal and focused — tests should assert behavior, not implementation details.
