//
//  IntentReporting.swift
//  SwiftUIIntents
//

import SwiftUI
internal import AsyncButton

/// Publishes what an executor knows to the views around it: the error state and
/// error events through preferences, the events of every run through a third,
/// and optionally `isLoading` through the environment.
struct IntentReportingModifier<Result: Sendable>: ViewModifier {
    let executor: IntentExecutor<Result>
    /// `IntentButton` gets `isLoading` from `AsyncButton`; other triggers set it here.
    let publishesLoading: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if publishesLoading {
            reporting(content)
                .environment(\.isLoading, executor.phase == .running)
        } else {
            reporting(content)
        }
    }

    private func reporting(_ content: Content) -> some View {
        content
            .preference(
                key: IntentErrorPreferenceKey.self,
                value: .init(executor.state.error)
            )
            .preference(
                key: IntentErrorEventPreferenceKey.self,
                value: executor.latestErrorEvent
            )
            .preference(
                key: IntentEventPreferenceKey.self,
                value: executor.events
            )
    }
}

extension View {
    func intentReporting<Result: Sendable>(
        _ executor: IntentExecutor<Result>,
        publishesLoading: Bool = true
    ) -> some View {
        modifier(IntentReportingModifier(executor: executor, publishesLoading: publishesLoading))
    }
}
