//
//  IntentBinding.swift
//  SwiftUIIntents
//
//  Created by Valeriy Malishevskyi on 29.04.2025.
//

import SwiftUI

/// A dynamic property that connects a SwiftUI view to an intent executor.
@MainActor public struct IntentBinding<PerformResult: Sendable> : DynamicProperty {
    /// The current intent associated with this binding.
    ///
    /// Carried directly rather than read back off the executor: the executor is
    /// long-lived, while this value is rebuilt from the view on every evaluation
    /// and so always reflects the current arguments.
    public let intent: (any Intent<PerformResult>)?

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

    /// Identity of the underlying executor, used by tests to detect that state
    /// was silently discarded and rebuilt across a re-render.
    var executorIdentity: ObjectIdentifier {
        ObjectIdentifier(executor)
    }

    init(
        executor: IntentExecutor<PerformResult>,
        intent: (any Intent<PerformResult>)?,
        environment: EnvironmentValues
    ) {
        self.executor = executor
        self.intent = intent
        self.environment = environment
    }
    
    /// Executes the bound intent using the current SwiftUI environment as context.
    public func perform() async {
        guard let intent else {
            return
        }

        await perform(intent)
    }

    func perform(_ intent: any Intent<PerformResult>) async {
        // Builds the context and hands it over; the executor installs it, so
        // callers that skip this binding are covered too.
        let context = IntentContextContainer(environment: environment)

        await executor.perform(intent, context: context)
    }
}
