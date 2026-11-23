//
//  IntentExecutionContext.swift
//  SwiftUIIntents
//

import SwiftUI
internal import ServiceContextModule

/// Runs `operation` with `context` installed as the current intent context.
///
/// Every path that performs an intent goes through here: `IntentExecutor`
/// wraps the view-driven runs, and `_TestingIntentExecutor` wraps the ones tests
/// drive. Keeping it in one place is deliberate: when the binding installed the
/// context and the testing executor did not, intents using `@IntentContext`
/// trapped under test. It sits at the executor rather than at the binding for
/// the same reason — reaching the executor directly, as tests do, must be safe.
@MainActor
func withIntentContext<T>(
    _ context: IntentContextContainer,
    operation: () async throws -> T
) async rethrows -> T {
    var serviceContext = ServiceContext.topLevel
    serviceContext[IntentContextKey.self] = context

    return try await ServiceContext.withValue(serviceContext) {
        try await operation()
    }
}
