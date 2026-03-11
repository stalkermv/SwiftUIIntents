//
//  IntentButton.swift
//  SwiftUIIntents
//
//  Created by Valeriy Malishevskyi on 29.04.2025.
//

import SwiftUI
internal import ServiceContextModule
internal import AsyncButton

/// Controls how `IntentButton` behaves when its intent is unavailable.
public enum IntentButtonMode {
    /// The button is enabled and visible when intent is available. It is disabled when intent is not available.
    case disable
    /// The button is enabled and visible when intent is available. It is hidden when intent is not available.
    case hide
    /// The button is enabled and visible when intent is available. It is removed when intent is not available.
    case remove
}

/// A button wrapper that executes an intent and exposes its execution state to the label.
public struct IntentButton<Content, PerformResult>: View
where Content: View, PerformResult: Sendable {
    
    @IntentState private var result: PerformResult?
    
    private let content: (IntentBinding<PerformResult>) -> Content
    
    /// Builds the content using the current `IntentBinding`.
    public var body: some View {
        content($result)
    }
    
    /// Creates an intent button from an optional intent value.
    public init<T, Label>(
        role: ButtonRole? = nil,
        mode: IntentButtonMode = .disable,
        _ intent: T?,
        @ViewBuilder label: @escaping () -> Label
    ) where Content == IntentButtonWrapper<Label, PerformResult>, T: Intent, T.PerformResult == PerformResult {
        self._result = IntentState(intent)
        self.content = { binding in
            IntentButtonWrapper(role: role, mode: mode, binding, label: label)
        }
    }
}

extension IntentButton {
    /// Creates an intent button from a non-optional intent value.
    public init<T, Label>(
        role: ButtonRole? = nil,
        mode: IntentButtonMode = .disable,
        _ intent: T,
        @ViewBuilder label: @escaping () -> Label
    ) where Content == IntentButtonWrapper<Label, PerformResult>, T: Intent, T.PerformResult == PerformResult {
        self.init(role: role, mode: mode, intent as Optional<T>, label: label)
    }
}

extension IntentButton {
    /// Creates an intent button backed by an existing `IntentBinding`.
    public init<Label>(
        role: ButtonRole? = nil,
        mode: IntentButtonMode = .disable,
        _ binding: IntentBinding<PerformResult>,
        @ViewBuilder label: @escaping () -> Label
    ) where Content == IntentButtonWrapper<Label, PerformResult> {
        self._result = IntentState(PerformResult.self)
        self.content = { _ in
            IntentButtonWrapper(role: role, mode: mode, binding, label: label)
        }
    }
}

/// The concrete view that renders and drives the underlying async button.
public struct IntentButtonWrapper<Content: View, PerformResult: Sendable> : View {
    
    let buttonRole: ButtonRole?
    let buttonMode: IntentButtonMode
    let label: () -> Content
    
    let intentBinding: IntentBinding<PerformResult>
    
    /// Creates a wrapper around a previously prepared `IntentBinding`.
    public init(
        role: ButtonRole?,
        mode: IntentButtonMode,
        _ intentBinding: IntentBinding<PerformResult>,
        @ViewBuilder label: @escaping () -> Content
    ) {
        self.buttonRole = role
        self.buttonMode = mode
        self.intentBinding = intentBinding
        self.label = label
    }
    
    public var body: some View {
        AsyncButton(role: buttonRole, action: action, label: label)
            .disabled(intentBinding.intent == nil)
            .hidden(
                intentBinding.intent == nil && buttonMode != .disable,
                remove: buttonMode == .remove
            )
            .preference(
                key: IntentErrorPreferenceKey.self,
                value: .init(intentBinding.error)
            )
            .preference(
                key: IntentErrorEventPreferenceKey.self,
                value: intentBinding.errorEvent
            )
    }
    
    private func action() async {
        await intentBinding.perform()
    }
}



extension View {

    /// Hide or show the view based on a boolean value.
    ///
    /// Example for visibility:
    ///
    ///     Text("Label")
    ///         .hidden(true)
    ///
    /// Example for complete removal:
    ///
    ///     Text("Label")
    ///         .hidden(true, remove: true)
    ///
    /// - Parameters:
    ///   - hidden: Set to `false` to show the view. Set to `true` to hide the view.
    ///   - remove: Boolean value indicating whether or not to remove the view.
    func hidden(
        _ isHidden: Bool,
        transition: AnyTransition = .identity,
        remove: Bool = false
    ) -> some View {
        modifier(
            HiddenModifier(
                isHidden: isHidden,
                transition: transition,
                remove: remove
            )
        )
    }
}

private struct HiddenModifier: ViewModifier {

    private var isHidden: Bool
    private var remove: Bool
    private var transition: AnyTransition

    init(
        isHidden: Bool,
        transition: AnyTransition = .opacity,
        remove: Bool = false
    ) {
        self.isHidden = isHidden
        self.transition = transition
        self.remove = remove
    }

    func body(content: Content) -> some View {
        if isHidden {
            if !remove {
                content.hidden()
            }
        } else {
            content
                .transition(transition)
        }
    }
}

extension View {
    /// Performs an intent whenever the supplied equatable value changes.
    public func onChange<T>(of equatable: T?, trigger intent: (some Intent)?) -> some View
    where T: Equatable {
        let modifier = OnChangeIntentModifier(
            equatable: equatable,
            intent: intent
        )
        
        return self.modifier(modifier)
    }
}

struct OnChangeIntentModifier<T, I>: ViewModifier
where T: Equatable, I: Intent {
    
    let equatable: T?
    let intent: I?
    
    @IntentState(I.PerformResult.self)
    private var intentState
    
    init(equatable: T?, intent: I?) {
        self.equatable = equatable
        self.intent = intent
        
        _intentState = IntentState(intent)
    }
    
    func body(content: Content) -> some View {
        content
            .task(id: equatable) {
                await $intentState.perform()
            }
            .environment(\.isLoading, $intentState.isExecuting)
            .preference(
                key: IntentErrorPreferenceKey.self,
                value: .init($intentState.error)
            )
            .preference(
                key: IntentErrorEventPreferenceKey.self,
                value: $intentState.errorEvent
            )
    }
}

extension Intent {
    /// Returns a new intent that executes `self` and then `other`.
    public func combined<T: Intent>(with other: T) -> CombinedIntent<Self, T> {
        CombinedIntent(self, other)
    }
    
    /// Returns a new intent that executes `self` and `other` concurrently.
    public func combined<T: Intent>(simultaneously other: T) -> SimultaneousCombinedIntent<Self, T> {
        SimultaneousCombinedIntent(self, other)
    }
}

/// An intent that runs two intents concurrently and returns both results.
public struct SimultaneousCombinedIntent<I1: Intent, I2: Intent>: Intent {
    
    public typealias PerformResult = (I1.PerformResult, I2.PerformResult)
    
    let first: I1
    let second: I2
    
    init(_ first: I1, _ second: I2) {
        self.first = first
        self.second = second
    }
 
    /// Executes both wrapped intents concurrently.
    public func perform(context: Context) async throws -> PerformResult {
        async let firstResult: I1.PerformResult = try await first.perform(context: context)
        async let secondResult: I2.PerformResult = try await second.perform(context: context)
        
        return (try await firstResult, try await secondResult)
    }
}

/// An intent that runs two intents sequentially and returns both results.
public struct CombinedIntent<I1: Intent, I2: Intent>: Intent {
    
    public typealias PerformResult = (I1.PerformResult, I2.PerformResult)
    
    let first: I1
    let second: I2
    
    init(_ first: I1, _ second: I2) {
        self.first = first
        self.second = second
    }
 
    /// Executes the wrapped intents in order.
    public func perform(context: Context) async throws -> PerformResult {
        let firstResult: I1.PerformResult = try await first.perform(context: context)
        let secondResult: I2.PerformResult = try await second.perform(context: context)
        return (firstResult, secondResult)
    }
}
