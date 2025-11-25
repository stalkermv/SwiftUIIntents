//
//  AsyncButton.swift
//  CustomComponents
//
//  Created by Valeriy Malishevskyi on 13.05.2025.
//

import SwiftUI

/// A SwiftUI button that supports asynchronous actions with execution control and optional role and styling.
///
/// `AsyncButton` triggers an `async` action when tapped, while managing execution state
/// such as disabling the button during task execution. It supports roles (e.g. `.destructive`) and
/// can be customized via `AsyncButtonOptions`.
///
/// ```swift
/// AsyncButton {
///     try await Task.sleep(nanoseconds: 1_000_000_000)
///     print("Action complete!")
/// } label: {
///     Text("Submit")
/// }
/// ```
///
/// - Note: Internally, this button uses a unique `executionID` to trigger side effects via a custom modifier.
///
/// - Parameters:
///   - role: The semantic role of the button (e.g., `.destructive`). Default is `nil`.
///   - options: Behavior options that affect execution (e.g. disables during execution). Default is empty.
///   - action: An async closure to execute on tap.
///   - label: A `ViewBuilder` closure that generates the button’s label.
public struct AsyncButton<Label: View>: View {

    private let action: () async -> Void
    private let label: () -> Label
    private let role: ButtonRole?
    private let options: AsyncButtonOptions
    
    var executionModifier: AsyncButtonExecutionModifier {
        AsyncButtonExecutionModifier(
            executionID: executionID,
            options: options,
            isDisabled: $isDisabled,
            action: action
        )
    }
    
    @State private var isDisabled = false
    @State private var executionID: UUID?
    
    /// Creates an `AsyncButton` with the given role, options, async action, and label.
    ///
    /// - Parameters:
    ///   - role: The button's semantic role, such as `.cancel` or `.destructive`. Default is `nil`.
    ///   - options: A set of flags controlling how the async action behaves (e.g., auto-disabling). Default is `[]`.
    ///   - action: An `async` closure to execute when the button is tapped.
    ///   - label: A closure that returns the button’s label view.
    public init(
        role: ButtonRole? = nil,
        options: AsyncButtonOptions = [],
        action: @escaping () async -> Void,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.role = role
        self.options = options
        self.action = action
        self.label = label
    }
    
    public var body: some View {
        Button(role: role, action: performAction, label: label)
            .disabled(isDisabled)
            .modifier(executionModifier)
    }
    
    private func performAction() {
        executionID = UUID()
    }
}
