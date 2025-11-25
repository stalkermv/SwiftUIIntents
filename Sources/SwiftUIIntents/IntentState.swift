//
//  IntentState.swift
//  SwiftUIIntents
//
//  Created by Valeriy Malishevskyi on 29.04.2025.
//

import SwiftUI

@MainActor @propertyWrapper
public struct IntentState<PerformResult: Sendable>: DynamicProperty {
    @Environment(\.self) private var environment
    
    /// The executor that manages the intent execution and state.
    @Bindable private var executor: IntentExecutor<PerformResult>
    
    private let intent: (any Intent<PerformResult>)?
    
    public var wrappedValue: PerformResult? {
        executor.state.value
    }
    
    public var projectedValue: IntentBinding<PerformResult> {
        IntentBinding(executor: executor, environment: environment)
    }
    
    nonisolated public func update() {
        Task {
            await executor.updateIntent(intent)
        }
    }
}

extension IntentState {
    
    public init(_ result: PerformResult.Type) {
        let executor = IntentExecutor<PerformResult>(intent: nil)
        _executor = .init(wrappedValue: executor)
        self.intent = nil
    }
    
    @MainActor public init<I: Intent>(_ intent: I?)
    where I.PerformResult == PerformResult {
        _executor = .init(wrappedValue: .init(intent: intent))
        self.intent = intent
    }
    
    public init<I: Intent>(wrappedValue: I.PerformResult? = nil, _ intent: I? = nil)
    where PerformResult == I.PerformResult {
        _executor = .init(wrappedValue: .init(intent: intent))
        self.intent = intent
    }
}
