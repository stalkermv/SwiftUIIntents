//
//  HiddenModifier.swift
//  SwiftUIIntents
//

import SwiftUI

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

