//
//  EmptyIntentResult.swift
//  SwiftUIIntents
//
//  Created by Valeriy Malishevskyi on 29.04.2025.
//

/// A marker result used by intents that perform side effects without returning data.
public struct EmptyIntentResult: Sendable { }

extension Intent where PerformResult == EmptyIntentResult {
    /// Adapts a no-value intent implementation to the `EmptyIntentResult` convention.
    @MainActor public func perform(context: Context) async throws -> EmptyIntentResult {
        let _ : Void = try await perform(context: context)
        return EmptyIntentResult()
    }
}
