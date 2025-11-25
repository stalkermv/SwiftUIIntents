//
//  EmptyIntentResult.swift
//  SwiftUIIntents
//
//  Created by Valeriy Malishevskyi on 29.04.2025.
//

public struct EmptyIntentResult: Sendable { }

extension Intent where PerformResult == EmptyIntentResult {
    @MainActor public func perform(context: Context) async throws -> EmptyIntentResult {
        let _ : Void = try await perform(context: context)
        return EmptyIntentResult()
    }
}
