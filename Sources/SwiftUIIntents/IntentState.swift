//
//  IntentState.swift
//  SwiftUIIntents
//
//  Created by Valeriy Malishevskyi on 29.04.2025.
//

import SwiftUI

/// Stores an intent executor in SwiftUI state and exposes its latest result.
@MainActor @propertyWrapper
public struct IntentState<PerformResult: Sendable>: DynamicProperty {
    @Environment(\.self) private var environment
    
    /// SwiftUI-owned storage.
    ///
    /// This was `@Bindable`, which is not a `DynamicProperty` and so gets no
    /// storage box: every reconstruction of the enclosing view built a fresh
    /// executor and discarded the execution state.
    @State private var executor: IntentExecutor<PerformResult>

    private let intent: (any Intent<PerformResult>)?

    /// The latest successful result produced by the bound intent.
    public var wrappedValue: PerformResult? {
        executor.state.value
    }

    /// A binding-like interface for performing the intent and observing execution state.
    public var projectedValue: IntentBinding<PerformResult> {
        IntentBinding(executor: executor, intent: intent, environment: environment)
    }

    /// Retained as a no-op.
    ///
    /// This used to push the intent into the executor from a detached `Task`,
    /// which arrived after `body` had been evaluated and in no defined order
    /// relative to a tap. The intent now travels on the binding, rebuilt from
    /// the current view value on every evaluation, so nothing needs syncing.
    ///
    /// The declaration stays because it is `public`.
    nonisolated public func update() {}
}

extension IntentState {
    /// Creates an empty state container for a given result type.
    public init(_ result: PerformResult.Type) {
        _executor = .init(wrappedValue: IntentExecutor<PerformResult>())
        self.intent = nil
    }

    /// Creates intent state bound to an optional intent instance.
    @MainActor public init<I: Intent>(_ intent: I?)
    where I.PerformResult == PerformResult {
        _executor = .init(wrappedValue: IntentExecutor<PerformResult>())
        self.intent = intent
    }

    /// Creates intent state with an optional initial wrapped value and intent.
    public init<I: Intent>(wrappedValue: I.PerformResult? = nil, _ intent: I? = nil)
    where PerformResult == I.PerformResult {
        _executor = .init(wrappedValue: IntentExecutor<PerformResult>())
        self.intent = intent
    }
}
