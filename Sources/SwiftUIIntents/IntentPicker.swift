//
//  IntentPicker.swift
//  SwiftUIIntents
//
//  Created by Valeriy Malishevskyi on 05.05.2026.
//

import SwiftUI

/// A picker that commits user selection changes by executing an intent.
///
/// The picker shows the new selection at once, runs the intent, and returns to the
/// value you supply as the source of truth when the intent finishes. While the
/// intent runs the picker is disabled and `isLoading` is `true`.
///
/// ```swift
/// IntentPicker(theme, { SetThemeIntent(theme: $0) }) {
///     Text("Light").tag(Theme.light)
///     Text("Dark").tag(Theme.dark)
/// } label: {
///     Text("Theme")
/// }
/// ```
public struct IntentPicker<Label, SelectionValue, Content, I>: View
where Label: View, SelectionValue: Hashable, Content: View, I: Intent {
    private let currentSelection: SelectionValue
    private let makeIntent: (SelectionValue) -> I?
    private let content: Content
    private let label: Label
    private let currentValueLabel: (() -> AnyView)?

    @State private var pendingRequest: PendingSelectionRequest<SelectionValue, I>?
    @State private var executor = IntentExecutor<I.PerformResult>()
    @Environment(\.self) private var environment

    private init(
        _ selection: SelectionValue,
        _ intent: @escaping (SelectionValue) -> I?,
        currentValueLabel: (() -> AnyView)?,
        @ViewBuilder content: () -> Content,
        @ViewBuilder label: () -> Label
    ) {
        self.currentSelection = selection
        self.makeIntent = intent
        self.currentValueLabel = currentValueLabel
        self.content = content()
        self.label = label()
    }

    public var body: some View {
        picker
            .disabled(isBusy)
            .intentReporting(executor)
            .task(id: pendingRequest?.id) {
                await performPendingRequest()
            }
    }

    private var displayedSelection: SelectionValue {
        pendingRequest?.selection ?? currentSelection
    }

    private var isBusy: Bool {
        pendingRequest != nil || executor.phase == .running
    }

    private var selection: Binding<SelectionValue> {
        Binding(
            get: { displayedSelection },
            set: commitSelection
        )
    }

    @ViewBuilder
    private var picker: some View {
        if let currentValueLabel {
            if #available(iOS 18.0, macOS 15.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *) {
                Picker(
                    selection: selection,
                    content: { content },
                    label: { label },
                    currentValueLabel: currentValueLabel
                )
            } else {
                Picker(
                    selection: selection,
                    content: { content },
                    label: { label }
                )
            }
        } else {
            Picker(
                selection: selection,
                content: { content },
                label: { label }
            )
        }
    }

    private func commitSelection(_ newSelection: SelectionValue) {
        guard !isBusy else {
            return
        }

        guard newSelection != displayedSelection else {
            return
        }

        guard let intent = makeIntent(newSelection) else {
            return
        }

        pendingRequest = PendingSelectionRequest(
            selection: newSelection,
            intent: intent
        )
    }

    private func performPendingRequest() async {
        guard let request = pendingRequest else {
            return
        }

        await executor.perform(
            request.intent,
            context: IntentContextContainer(environment: environment)
        )
        finish(request)
    }

    private func finish(_ request: PendingSelectionRequest<SelectionValue, I>) {
        guard pendingRequest?.id == request.id else {
            return
        }

        pendingRequest = nil
    }
}

extension IntentPicker {
    /// Creates a picker that builds an optional intent for each selected value.
    ///
    /// When a user selects a new value, the picker displays that value optimistically
    /// until the intent finishes, then returns to the supplied source-of-truth value.
    public init(
        _ selection: SelectionValue,
        _ intent: @escaping (SelectionValue) -> I?,
        @ViewBuilder content: () -> Content,
        @ViewBuilder label: () -> Label
    ) {
        self.init(
            selection,
            intent,
            currentValueLabel: nil,
            content: content,
            label: label
        )
    }

    /// Creates a picker with a concrete label view.
    public init(
        _ selection: SelectionValue,
        _ intent: @escaping (SelectionValue) -> I?,
        label: Label,
        @ViewBuilder content: () -> Content
    ) {
        self.init(
            selection,
            intent,
            currentValueLabel: nil,
            content: content,
            label: { label }
        )
    }

    /// Creates a picker that also supplies a current-value label for modern picker styles.
    @available(iOS 18.0, macOS 15.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
    public init<CurrentValueLabel: View>(
        _ selection: SelectionValue,
        _ intent: @escaping (SelectionValue) -> I?,
        @ViewBuilder content: () -> Content,
        @ViewBuilder label: () -> Label,
        @ViewBuilder currentValueLabel: @escaping () -> CurrentValueLabel
    ) {
        self.init(
            selection,
            intent,
            currentValueLabel: { AnyView(currentValueLabel()) },
            content: content,
            label: label
        )
    }
}

private struct PendingSelectionRequest<SelectionValue, I: Intent>: Identifiable {
    let id = UUID()
    let selection: SelectionValue
    let intent: I
}
