---
inclusion: fileMatch
fileMatchPattern: "**/*.swift"
---
# Swift Concurrency Pro (Paul Hudson / twostraws)

Review Swift concurrency code for correctness, modern API usage, and adherence to project conventions. Report only genuine problems — do not nitpick or invent issues.

Source: https://github.com/twostraws/Swift-Concurrency-Agent-Skill (MIT License)

## Core Instructions

- Target Swift 5.9+ (this project uses swift-tools-version 5.9, macOS 14+).
- Prefer structured concurrency (task groups) over unstructured (`Task {}`).
- Prefer Swift concurrency over Grand Central Dispatch for new code. GCD is still acceptable in low-level code, framework interop, or performance-critical synchronous work where queues and locks are the right tool.
- If an API offers both `async`/`await` and closure-based variants, always prefer `async`/`await`.
- Do not introduce third-party concurrency frameworks without asking first.
- Do not suggest `@unchecked Sendable` to fix compiler errors. Prefer actors, value types, or `sending` parameters instead.

## Hotspots — Known Dangerous Patterns

When any of these appear in code, inspect carefully:

- **`DispatchQueue`** — In app-level code, usually has a Swift concurrency equivalent. GCD still fine in low-level libraries and performance-critical synchronous sections.
- **`Task.detached`** — Rarely correct. Usually means the author wanted background execution but should have used a task group or `@concurrent`.
- **`Task {}` inside a loop** — Frequently a bad idea; evaluate whether it should be a task group.
- **`withCheckedContinuation`** — Audit every code path to ensure continuation is resumed exactly once.
- **`AsyncStream` (closure-based initializer)** — Prefer `AsyncStream.makeStream(of:)` factory.
- **`@unchecked Sendable`** — Should be very rare. Check whether the type actually provides thread safety.
- **`MainActor.run {}`** — Often unnecessary if surrounding code is already `@MainActor`.
- **Actors** — Check for reentrancy bugs: any method that reads state, awaits, then writes state is suspect.
- **Force unwraps after `await` inside actors** — Prime target for latent crash; another caller may have set the value to nil during suspension.

## Actor Reentrancy

The most common concurrency bug: after every `await` inside an actor, all assumptions about the actor's state are invalidated because other calls may have run in the meantime.

```swift
// BUG: After the await, items[key] may already have been set by another caller.
actor Cache {
    var items: [String: Data] = [:]
    func load(_ key: String) async throws -> Data {
        if items[key] == nil {
            items[key] = try await download(key)
        }
        return items[key]!  // CRASH if cleared by another caller
    }
}

// FIX: Capture result in local, then assign.
actor Cache {
    var items: [String: Data] = [:]
    func load(_ key: String) async throws -> Data {
        if let cached = items[key] { return cached }
        let data = try await download(key)
        items[key] = data
        return data
    }
}
```

## Structured Concurrency

- Use `async let` for fixed number of independent operations returning different types.
- Use task groups for dynamic number of operations of the same type.
- Use `withDiscardingTaskGroup` for fire-and-forget child tasks (Swift 5.9+).

## Unstructured Tasks

- `Task {}` inherits caller's actor isolation; `Task.detached {}` does not.
- `Task.detached` is rarely the right choice — prefer `Task {}` with explicit isolation changes.
- Cancellation is cooperative — task body must check `Task.checkCancellation()` or `Task.isCancelled`.

## Bug Patterns

- Actor reentrancy: check-then-act across `await`
- Continuation resumed zero times (caller hangs forever)
- Continuation resumed twice (runtime crash)
- Unstructured tasks in a loop (no cancellation, no error collection)
- Swallowed errors in Task closures
- Blocking the main actor with synchronous work
- Unbounded AsyncStream buffer
- Ignoring `CancellationError` in catch blocks
- `@unchecked Sendable` hiding real races

## Interop Patterns

- Completion handlers → `async`/`await` via `withCheckedThrowingContinuation`
- Delegates → `AsyncStream` via `makeStream(of:)`
- `DispatchQueue.main.async` → `@MainActor`
- `DispatchQueue.global().async` → `@concurrent` or Task Group
- Serial `DispatchQueue` → `actor`
