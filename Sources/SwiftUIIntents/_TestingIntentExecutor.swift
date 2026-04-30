//
//  _TestingIntentExecutor.swift
//  SwiftUIIntents
//
//  Created by Valeriy Malishevskyi on 30.04.2026.
//

import SwiftUI

@_spi(Testing)
public struct _TestingIntentExecutor<I: Intent> {
    
    private let intent: I
    private let environment: EnvironmentValues
    
    @_spi(Testing)
    public init(_ intent: I, environment: EnvironmentValues) {
        self.intent = intent
        self.environment = environment
    }
    
    @MainActor @_spi(Testing)
    public func run() async throws -> I.PerformResult {
        let context = IntentContextContainer(environment: environment)
        return try await intent.perform(context: context)
    }
}
