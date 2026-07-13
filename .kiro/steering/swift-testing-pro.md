---
inclusion: fileMatch
fileMatchPattern: "**/*Test*.*"
---
# Swift Testing Pro (Paul Hudson / twostraws)

Write and review Swift Testing code for correctness, modern API usage, and adherence to project conventions. Report only genuine problems — do not nitpick or invent issues.

Source: https://github.com/twostraws/Swift-Testing-Agent-Skill (MIT License)

## Core Rules

- Target Swift 6.2 or later, using modern Swift concurrency.
- All new unit/integration tests must use Swift Testing — not XCTest. UI tests still require XCTest.
- Prefer structs over classes for test suites. Use `init()` instead of setUp/tearDown.
- `@Suite` is unnecessary unless naming or attaching traits — any type with `@Test` methods is automatically a suite.
- No need to prefix test methods with `test` — use descriptive names like `userCanLogOut()`.
- Tests run in parallel by default — each test must be independent of execution order.
- Never use `!` to negate Booleans in `#expect` or `#require` (defeats macro expansion). Use `== false` instead.
- If a test has no `#expect` or `#require`, it is assumed to have passed.

## Test Structure (FIRST)

- **Fast:** Dozens per second, no live networking.
- **Isolated:** No dependency on other tests or external state.
- **Repeatable:** Same result every time, regardless of order or count.
- **Self-verifying:** Unambiguous pass/fail.
- **Timely:** Written before or alongside production code.

## Test Generation Heuristics

For a given function, aim to generate:
- Happy path tests
- Boundary tests
- Invalid input tests
- Concurrency tests (if appropriate)

## `#expect` vs `#require`

- `#expect` — the actual assertion you care about. Continues on failure.
- `#require` — preconditions that must be true. Stops the test on failure (throws).
- Use `#require` to unwrap optionals: `let value = try #require(someOptional)`
- Use `#require` at the start of tests for setup verification.

## Parameterized Tests

Extremely powerful for covering many cases concisely:

```swift
@Test(arguments: ["admin", "editor", "viewer"])
func roleHasPermissions(role: String) {
    let user = User(role: role)
    #expect(user.permissions.isEmpty == false)
}
```

- At most two argument collections (Cartesian product, not zip).
- For pairwise zipping, pass `zip(collection1, collection2)`.

## Mocking & Dependency Injection

Unit tests should never do live networking. Mock the networking layer:

```swift
protocol URLSessionProtocol {
    func data(from url: URL) async throws -> (Data, URLResponse)
}

extension URLSession: URLSessionProtocol { }

class URLSessionMock: URLSessionProtocol {
    var testData: Data?
    var testError: (any Error)?

    func data(from url: URL) async throws -> (Data, URLResponse) {
        if let testError { throw testError }
        return (testData ?? Data(), URLResponse())
    }
}
```

Inject dependencies with default values so production call sites don't change:

```swift
func fetch(using session: any URLSessionProtocol = URLSession.shared) async throws { ... }
```

For `UserDefaults`, inject a unique suite per test:

```swift
let suite = "suite-\(UUID().uuidString)"
let userDefaults = UserDefaults(suiteName: suite)
defer { userDefaults?.removePersistentDomain(forName: suite) }
```

## Async Tests & Confirmation

- `confirmation(expectedCount:)` — verify an async event fires N times.
- All tested code must complete before the `confirmation()` closure returns.
- `confirmation(expectedCount: 0)` means "ensure this never happens."
- `.serialized` only works on parameterized tests (not individual tests).

```swift
@Test func workerRunsThreeTimes() async {
    let worker = Worker()
    await confirmation(expectedCount: 3) { confirm in
        for _ in 0..<3 {
            await worker.run()
            confirm()
        }
    }
}
```

## Time Limits

Use `.timeLimit(.minutes(N))` — **`.seconds()` is not available**.

```swift
@Test("Loading completes quickly", .timeLimit(.minutes(1)))
func loadNames() async { ... }
```

## Error Testing

Use `#expect(throws:)` with a specific error, not broad `Error.self`:

```swift
#expect(throws: GameError.notInstalled) {
    try game.play()
}
```

For "does not throw": `#expect(throws: Never.self) { try game.play() }`

For fine-grained control, use `do/catch` with `Issue.record()`:

```swift
do {
    try game.play()
    Issue.record("Expected an error to be thrown.")
} catch GameError.notPurchased {
    // success
} catch {
    Issue.record("Wrong error thrown: \(error)")
}
```

## Tags

```swift
extension Tag {
    @Tag static var networking: Self
}

@Test(.tags(.networking))
func fetchProfile() async throws { ... }
```

## Known Issues

```swift
withKnownIssue("Bug #42: sometimes returns empty") {
    #expect(result.isEmpty == false)
}
```

Add `isIntermittent: true` for flaky issues being debugged.

## Bug Tracking

```swift
@Test("Headings should be italic", .bug(id: 182))
func headingsAreItalic() { ... }
```

## Verification Methods (Source Location)

```swift
func verifyDivision(_ result: (quotient: Int, remainder: Int),
                    expected: (Int, Int),
                    sourceLocation: SourceLocation = #_sourceLocation) {
    #expect(result.quotient == expected.0, sourceLocation: sourceLocation)
    #expect(result.remainder == expected.1, sourceLocation: sourceLocation)
}
```

## Migration from XCTest (only when requested)

| XCTest | Swift Testing |
|--------|--------------|
| `XCTAssertEqual(a, b)` | `#expect(a == b)` |
| `XCTAssertTrue(x)` | `#expect(x)` |
| `XCTUnwrap(opt)` | `try #require(opt)` |
| `XCTFail("msg")` | `Issue.record("msg")` |
| `XCTAssertThrowsError` | `#expect(throws:)` |
| `XCTAssertIdentical(a, b)` | `#expect(a === b)` |

Steps: keep same type names (class → struct), remove `test` prefix, switch assertions, then look for parameterized test opportunities.
