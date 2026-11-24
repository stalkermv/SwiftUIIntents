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

/// A button that runs an intent and reports its progress through the environment
/// and the intent hooks.
///
/// ```swift
/// IntentButton(SaveDraftIntent(message: message)) {
///     Text("Save")
/// }
/// ```
///
/// While the intent runs the button disables itself, and `isLoading` is `true` in
/// the label's environment, so the label or a `ButtonStyle` draws the progress
/// indicator. The button does not draw one. Errors reach `onChangeIntentError` and
/// `onReceiveIntentError`. When the button is removed from the view hierarchy the
/// run is cancelled, unless the intent is a ``LongRunningIntent``.
public struct IntentButton<I: Intent, Label: View>: View {
    private let role: ButtonRole?
    private let mode: IntentButtonMode
    private let intent: I?
    private let handle: IntentHandle<I>?
    private let label: () -> Label

    @State private var executor = IntentExecutor<I.PerformResult>()
    @Environment(\.self) private var environment

    /// Creates a button that runs `intent` when it is pressed.
    ///
    /// - Parameters:
    ///   - intent: The intent to run, or `nil` when there is nothing to run.
    ///   - role: The button's role.
    ///   - mode: What the button does when `intent` is `nil`.
    ///   - handle: A handle that can cancel the run.
    ///   - label: The button's label.
    public init(
        _ intent: I?,
        role: ButtonRole? = nil,
        mode: IntentButtonMode = .disable,
        handle: IntentHandle<I>? = nil,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.role = role
        self.mode = mode
        self.handle = handle
        self.intent = intent
        self.label = label
    }

    public var body: some View {
        AsyncButton(role: role, action: run, label: label)
            .disabled(intent == nil)
            .hidden(intent == nil && mode != .disable, remove: mode == .remove)
            .intentReporting(executor, publishesLoading: false)
    }

    private func run() async {
        guard let intent else {
            return
        }

        await executor.perform(
            intent,
            context: IntentContextContainer(environment: environment),
            handle: handle
        )
    }
}

extension View {
    /// Runs an intent when the view appears and again whenever the supplied
    /// equatable value changes.
    ///
    /// A new value cancels the run that is still in flight and starts a new one, so
    /// an older, slower run cannot overwrite the result of a newer one. A cancelled
    /// run is not reported as an error. Removing the view cancels the run too.
    ///
    /// - Parameters:
    ///   - equatable: The value to watch.
    ///   - initial: Whether to run when the view appears. The default is `false`,
    ///     like SwiftUI's `onChange`.
    ///   - intent: The intent to run, or `nil`.
    ///   - handle: A handle that can cancel the run.
    public func onChange<T, I>(
        of equatable: T?,
        initial: Bool = false,
        trigger intent: I?,
        handle: IntentHandle<I>? = nil
    ) -> some View where T: Equatable, I: Intent {
        modifier(
            OnChangeIntentModifier(
                equatable: equatable,
                initial: initial,
                intent: intent,
                handle: handle
            )
        )
    }
}

struct OnChangeIntentModifier<T, I>: ViewModifier
where T: Equatable, I: Intent {
    let equatable: T?
    let initial: Bool
    let intent: I?
    let handle: IntentHandle<I>?

    @State private var executor = IntentExecutor<I.PerformResult>()
    @State private var owner = IntentTaskOwner()
    @Environment(\.self) private var environment

    func body(content: Content) -> some View {
        content
            .onChange(of: equatable, initial: initial) {
                guard let intent else {
                    return
                }

                let context = IntentContextContainer(environment: environment)
                owner.start(policy: .cancelAndRestart) { [executor, handle] in
                    await executor.perform(intent, context: context, handle: handle)
                }
            }
            .intentReporting(executor)
    }
}
