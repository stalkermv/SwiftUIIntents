//
//  IntentCustomPicker.swift
//  SwiftUIIntents
//

import SwiftUI
internal import CustomPicker

/// A custom picker that commits user selection changes by executing an intent.
///
/// Mirrors ``IntentPicker`` on top of `CustomPicker`, supporting required single
/// selection (`SelectionValue`), optional single selection (`SelectionValue?`
/// where choosing the active option deselects it to `nil`), and multiple
/// selection (`Set<SelectionValue>`).
public struct IntentCustomPicker<Label, SelectionValue, Content, I>: View
where Label: View, SelectionValue: Hashable, Content: View, I: Intent {
    private enum Mode {
        case single(current: SelectionValue, makeIntent: (SelectionValue) -> I?)
        case optional(current: SelectionValue?, makeIntent: (SelectionValue?) -> I?)
        case multiple(current: Set<SelectionValue>, makeIntent: (Set<SelectionValue>) -> I?)
    }

    private enum PendingSelection {
        case single(SelectionValue)
        case optional(SelectionValue?)
        case multiple(Set<SelectionValue>)
    }

    private struct PendingRequest: Identifiable {
        let id = UUID()
        let selection: PendingSelection
        let intent: I
    }

    private let mode: Mode
    private let content: Content
    private let label: Label
    private let currentValueLabel: (() -> AnyView)?

    @State private var pendingRequest: PendingRequest?
    @State private var executor = IntentExecutor<I.PerformResult>()
    @Environment(\.self) private var environment

    private init(
        mode: Mode,
        currentValueLabel: (() -> AnyView)?,
        @ViewBuilder content: () -> Content,
        @ViewBuilder label: () -> Label
    ) {
        self.mode = mode
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

    private var isBusy: Bool {
        pendingRequest != nil || executor.phase == .running
    }

    @ViewBuilder
    private var picker: some View {
        switch mode {
        case .single(let current, let makeIntent):
            let displayed = if case .single(let pending) = pendingRequest?.selection {
                pending
            } else {
                current
            }
            let binding = Binding(
                get: { displayed },
                set: { newValue in
                    commitIfNeeded(newValue != displayed, pending: .single(newValue)) {
                        makeIntent(newValue)
                    }
                }
            )
            makePicker(selection: binding)

        case .optional(let current, let makeIntent):
            let displayed = if case .optional(let pending) = pendingRequest?.selection {
                pending
            } else {
                current
            }
            let binding = Binding(
                get: { displayed },
                set: { newValue in
                    commitIfNeeded(newValue != displayed, pending: .optional(newValue)) {
                        makeIntent(newValue)
                    }
                }
            )
            makePicker(selection: binding)

        case .multiple(let current, let makeIntent):
            let displayed = if case .multiple(let pending) = pendingRequest?.selection {
                pending
            } else {
                current
            }
            let binding = Binding(
                get: { displayed },
                set: { newValue in
                    commitIfNeeded(newValue != displayed, pending: .multiple(newValue)) {
                        makeIntent(newValue)
                    }
                }
            )
            makePicker(selection: binding)
        }
    }

    @ViewBuilder
    private func makePicker(selection: Binding<SelectionValue>) -> some View {
        if let currentValueLabel {
            CustomPicker(
                selection: selection,
                content: { content },
                label: { label },
                currentValueLabel: currentValueLabel
            )
        } else {
            CustomPicker(
                selection: selection,
                content: { content },
                label: { label }
            )
        }
    }

    @ViewBuilder
    private func makePicker(selection: Binding<SelectionValue?>) -> some View {
        if let currentValueLabel {
            CustomPicker(
                selection: selection,
                content: { content },
                label: { label },
                currentValueLabel: currentValueLabel
            )
        } else {
            CustomPicker(
                selection: selection,
                content: { content },
                label: { label }
            )
        }
    }

    @ViewBuilder
    private func makePicker(selection: Binding<Set<SelectionValue>>) -> some View {
        if let currentValueLabel {
            CustomPicker(
                selection: selection,
                content: { content },
                label: { label },
                currentValueLabel: currentValueLabel
            )
        } else {
            CustomPicker(
                selection: selection,
                content: { content },
                label: { label }
            )
        }
    }

    private func commitIfNeeded(
        _ didChange: Bool,
        pending: PendingSelection,
        makeIntent: () -> I?
    ) {
        guard !isBusy, didChange, let intent = makeIntent() else {
            return
        }

        pendingRequest = PendingRequest(selection: pending, intent: intent)
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

    private func finish(_ request: PendingRequest) {
        guard pendingRequest?.id == request.id else {
            return
        }

        pendingRequest = nil
    }
}

extension IntentCustomPicker {
    /// Creates a single-selection custom picker that builds an optional intent
    /// for each selected value.
    @_disfavoredOverload
    public init(
        _ selection: SelectionValue,
        _ intent: @escaping (SelectionValue) -> I?,
        @ViewBuilder content: () -> Content,
        @ViewBuilder label: () -> Label
    ) {
        self.init(
            mode: .single(current: selection, makeIntent: intent),
            currentValueLabel: nil,
            content: content,
            label: label
        )
    }

    /// Creates a single-selection custom picker with a concrete label view.
    @_disfavoredOverload
    public init(
        _ selection: SelectionValue,
        _ intent: @escaping (SelectionValue) -> I?,
        label: Label,
        @ViewBuilder content: () -> Content
    ) {
        self.init(
            mode: .single(current: selection, makeIntent: intent),
            currentValueLabel: nil,
            content: content,
            label: { label }
        )
    }

    /// Creates a single-selection custom picker that supplies a current-value label.
    @_disfavoredOverload
    public init<CurrentValueLabel: View>(
        _ selection: SelectionValue,
        _ intent: @escaping (SelectionValue) -> I?,
        @ViewBuilder content: () -> Content,
        @ViewBuilder label: () -> Label,
        @ViewBuilder currentValueLabel: @escaping () -> CurrentValueLabel
    ) {
        self.init(
            mode: .single(current: selection, makeIntent: intent),
            currentValueLabel: { AnyView(currentValueLabel()) },
            content: content,
            label: label
        )
    }

    /// Creates an optional-selection custom picker that clears the selection to
    /// `nil` when the active option is chosen again.
    public init(
        _ selection: SelectionValue?,
        _ intent: @escaping (SelectionValue?) -> I?,
        @ViewBuilder content: () -> Content,
        @ViewBuilder label: () -> Label
    ) {
        self.init(
            mode: .optional(current: selection, makeIntent: intent),
            currentValueLabel: nil,
            content: content,
            label: label
        )
    }

    /// Creates an optional-selection custom picker with a concrete label view.
    public init(
        _ selection: SelectionValue?,
        _ intent: @escaping (SelectionValue?) -> I?,
        label: Label,
        @ViewBuilder content: () -> Content
    ) {
        self.init(
            mode: .optional(current: selection, makeIntent: intent),
            currentValueLabel: nil,
            content: content,
            label: { label }
        )
    }

    /// Creates an optional-selection custom picker that supplies a current-value label.
    public init<CurrentValueLabel: View>(
        _ selection: SelectionValue?,
        _ intent: @escaping (SelectionValue?) -> I?,
        @ViewBuilder content: () -> Content,
        @ViewBuilder label: () -> Label,
        @ViewBuilder currentValueLabel: @escaping () -> CurrentValueLabel
    ) {
        self.init(
            mode: .optional(current: selection, makeIntent: intent),
            currentValueLabel: { AnyView(currentValueLabel()) },
            content: content,
            label: label
        )
    }

    /// Creates a multiple-selection custom picker that builds an optional intent
    /// for each updated selection set.
    public init(
        _ selection: Set<SelectionValue>,
        _ intent: @escaping (Set<SelectionValue>) -> I?,
        @ViewBuilder content: () -> Content,
        @ViewBuilder label: () -> Label
    ) {
        self.init(
            mode: .multiple(current: selection, makeIntent: intent),
            currentValueLabel: nil,
            content: content,
            label: label
        )
    }

    /// Creates a multiple-selection custom picker with a concrete label view.
    public init(
        _ selection: Set<SelectionValue>,
        _ intent: @escaping (Set<SelectionValue>) -> I?,
        label: Label,
        @ViewBuilder content: () -> Content
    ) {
        self.init(
            mode: .multiple(current: selection, makeIntent: intent),
            currentValueLabel: nil,
            content: content,
            label: { label }
        )
    }

    /// Creates a multiple-selection custom picker that supplies a current-value label.
    public init<CurrentValueLabel: View>(
        _ selection: Set<SelectionValue>,
        _ intent: @escaping (Set<SelectionValue>) -> I?,
        @ViewBuilder content: () -> Content,
        @ViewBuilder label: () -> Label,
        @ViewBuilder currentValueLabel: @escaping () -> CurrentValueLabel
    ) {
        self.init(
            mode: .multiple(current: selection, makeIntent: intent),
            currentValueLabel: { AnyView(currentValueLabel()) },
            content: content,
            label: label
        )
    }
}

extension IntentCustomPicker where Label == EmptyView {
    /// Creates a single-selection custom picker without a visible label.
    @_disfavoredOverload
    public init(
        _ selection: SelectionValue,
        _ intent: @escaping (SelectionValue) -> I?,
        @ViewBuilder content: () -> Content
    ) {
        self.init(
            mode: .single(current: selection, makeIntent: intent),
            currentValueLabel: nil,
            content: content,
            label: { EmptyView() }
        )
    }

    /// Creates an optional-selection custom picker without a visible label.
    public init(
        _ selection: SelectionValue?,
        _ intent: @escaping (SelectionValue?) -> I?,
        @ViewBuilder content: () -> Content
    ) {
        self.init(
            mode: .optional(current: selection, makeIntent: intent),
            currentValueLabel: nil,
            content: content,
            label: { EmptyView() }
        )
    }

    /// Creates a multiple-selection custom picker without a visible label.
    public init(
        _ selection: Set<SelectionValue>,
        _ intent: @escaping (Set<SelectionValue>) -> I?,
        @ViewBuilder content: () -> Content
    ) {
        self.init(
            mode: .multiple(current: selection, makeIntent: intent),
            currentValueLabel: nil,
            content: content,
            label: { EmptyView() }
        )
    }
}
