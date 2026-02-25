---
name: logging-level
description: Enforces consistent and intentional usage of logging levels across applications and packages.
---

# Logging Level Guidelines

This document defines **strict rules** for when to use each logging level.

The goal is:
- High signal in production
- Useful diagnostics in development
- Zero noise
- Clear operational observability

---

# Core Principle

Each log level must answer a specific question:

| Level  | Answers the Question |
|---------|----------------------|
| trace   | What exactly happened step-by-step? |
| debug   | Why did this happen? |
| info    | What meaningful event occurred? |
| warn    | What unexpected but recoverable issue occurred? |
| error   | What failed and requires attention? |
| fatal   | What unrecoverable failure occurred? |

---

# TRACE

## Purpose
Fine-grained execution flow reconstruction.

## Use For
- Method entry / exit
- Parameter values (non-sensitive)
- Intermediate state changes
- Branch decisions
- Loop iterations
- Detailed workflow steps
- Concurrency diagnostics

## Rules
- Never log business summaries here
- Never log user-facing events
- Must be safe to disable entirely
- Should not significantly impact performance

## Typical Usage
Development-only or deep production debugging.

---

# DEBUG

## Purpose
Developer-focused diagnostics.

## Use For
- Guard evaluations
- Business rule decisions
- External service calls (before/after)
- Cache hits/misses
- Repository queries
- Domain event publishing
- Configuration values at startup

## Rules
- Must not spam per-iteration logs
- Should provide reasoning, not noise
- No sensitive data

## Typical Usage
Enabled in development and staging.
Sometimes selectively enabled in production.

---

# INFO

## Purpose
Operational visibility of meaningful events.

## Use For
- Application start/stop
- User-triggered operations
- Successful workflows
- Job execution start/finish
- Important state transitions
- External system connection success

## Rules
- Must be business-relevant
- Must not be technical noise
- Should be understandable by operations

## Typical Usage
Always enabled in production.

---

# WARN

## Purpose
Unexpected but recoverable conditions.

## Use For
- Fallback logic triggered
- Retry attempts
- Validation inconsistencies
- Missing optional configuration
- Degraded performance
- External service temporary issues

## Rules
- System continues functioning
- Must not represent failure
- Should include enough context for investigation

## Example Situations
- Cache unavailable, using direct database
- Retry attempt 2/3
- Optional dependency missing

## Typical Usage
Always enabled in production.

---

# ERROR

## Purpose
Failures that affect a specific operation.

## Use For
- Unhandled exceptions (caught at boundary)
- Failed workflows
- Failed transactions
- Domain invariants violated
- External API failures without fallback

## Rules
- Operation failed
- User impact likely
- Must contain actionable context
- Must include correlation identifiers

## Important
Errors must be logged once at the boundary.
Do not log and rethrow repeatedly.

## Typical Usage
Always enabled in production.

---

# FATAL

## Purpose
Unrecoverable system failure.

## Use For
- Application cannot start
- Critical dependency unavailable
- Corrupted state detected
- Process termination scenarios
- Database unreachable at startup

## Rules
- System cannot continue safely
- Immediate operator action required
- Usually followed by shutdown

## Typical Usage
Always enabled in production.

---

# Additional Enforcement Rules

## 1. No Log Duplication
Log failures at system boundaries only.
Do not log and rethrow at every layer.

## 2. No Sensitive Data
Never log:
- Passwords
- Tokens
- Personal data
- Secrets

## 3. Correlation
Errors and warnings must include:
- Correlation ID
- Aggregate ID (if applicable)
- User ID (if safe)

## 4. Structured Logging Preferred
Use structured fields instead of string interpolation when supported.

---

# Summary Matrix

| Scenario                                   | Level  |
|--------------------------------------------|--------|
| Entering method                            | trace  |
| Guard failed (handled)                     | debug  |
| Workflow started                           | info   |
| Fallback triggered                         | warn   |
| Operation failed                           | error  |
| Application cannot boot                    | fatal  |

---

# Final Rule

If disabling a log level would remove important production visibility,  
it does not belong in `trace` or `debug`.

If a log entry creates noise in dashboards,  
it does not belong in `info`.

Be intentional. Logging is an architectural decision.