//
//  IntentBinding.swift
//  SwiftUIIntents
//
//  Created by Valeriy Malishevskyi on 29.04.2025.
//

import SwiftUI
internal import ServiceContextModule

/// A property wrapper that binds a SwiftUI view to an `Intent`.
@MainActor public struct IntentBinding<PerformResult: Sendable> : DynamicProperty {
    
    public var intent: (any Intent<PerformResult>)? {
        executor.intent
    }
    
    var error: Error? {
        executor.state.error
    }
    
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
    
    public func perform() async {
        let context = IntentContextContainer(environment: environment)
        var serviceContext = ServiceContext.topLevel
        serviceContext[IntentContextKey.self] = context
        
        await ServiceContext.withValue(serviceContext) {
            await executor.perform(context: context)
        }
    }
}
