import SwiftUI
import Testing
@_spi(Testing) @testable import SwiftUIIntents

/// No `PerformResult` typealias and no return value.
private struct NoResultIntent: Intent {
    let log: Recorder

    func perform(context: Context) async throws {
        log.calls += 1
    }
}

private struct TextResultIntent: Intent {
    func perform(context: Context) async throws -> String {
        "text"
    }
}

private final class Recorder: @unchecked Sendable {
    var calls = 0
}

@MainActor
@Suite("Intents without a result")
struct NoResultIntentTests {
    @Test("An intent that returns nothing needs no typealias and no return")
    func noResultIntentRuns() async throws {
        let log = Recorder()
        try await _TestingIntentExecutor(NoResultIntent(log: log), environment: EnvironmentValues()).run()

        #expect(log.calls == 1)
    }

    @Test("An intent that returns nothing has a Void result")
    func noResultIntentIsVoid() {
        #expect(NoResultIntent.PerformResult.self == Void.self)
        #expect(EmptyIntent.PerformResult.self == Void.self)
        #expect(DismissIntent.PerformResult.self == Void.self)
    }

    @Test("IntentButton accepts an intent with and without a result")
    func buttonAcceptsBoth() {
        _ = IntentButton(NoResultIntent(log: Recorder())) { Text("Save") }
        _ = IntentButton(TextResultIntent()) { Text("Load") }
        _ = IntentButton(DismissIntent()) { Text("Close") }
    }

    @Test("DismissIntent runs outside a presentation without failing")
    func dismissOutsidePresentation() async throws {
        try await _TestingIntentExecutor(DismissIntent(), environment: EnvironmentValues()).run()
    }
}
