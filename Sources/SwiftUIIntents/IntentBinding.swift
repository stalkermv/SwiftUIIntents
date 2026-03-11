//
//  IntentBinding.swift
//  SwiftUIIntents
//
//  Created by Valeriy Malishevskyi on 29.04.2025.
//

import SwiftUI
internal import ServiceContextModule

/// A dynamic property that connects a SwiftUI view to an intent executor.
@MainActor public struct IntentBinding<PerformResult: Sendable> : DynamicProperty {
    /// The current intent associated with this binding.
    public var intent: (any Intent<PerformResult>)? {
        executor.intent
    }
    
    var error: Error? {
        executor.state.error
    }
    
    var errorEvent: IntentErrorEvent? {
        executor.latestErrorEvent
    }
    
    /// Indicates whether the intent is currently executing.
    public var isExecuting: Bool {
        guard case .loading = executor.state else {
            return false
        }
        return true
    }
    
    private var executor: IntentExecutor<PerformResult>
    private let environment: EnvironmentValues
    
    init(executor: IntentExecutor<PerformResult>, environment: EnvironmentValues) {
        self.executor = executor
        self.environment = environment
    }
    
    /// Executes the bound intent using the current SwiftUI environment as context.
    public func perform() async {
        let context = IntentContextContainer(environment: environment)
        var serviceContext = ServiceContext.topLevel
        serviceContext[IntentContextKey.self] = context
        
        await ServiceContext.withValue(serviceContext) {
            await executor.perform(context: context)
        }
    }
}
