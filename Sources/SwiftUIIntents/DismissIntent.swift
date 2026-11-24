//
//  DismissIntent.swift
//  SwiftUIIntents
//

import SwiftUI

/// An intent that dismisses the presentation the triggering view is in.
///
/// It calls the `dismiss` action of the environment captured when the intent
/// runs, so it closes the sheet, popover or pushed screen that contains the
/// button, the same as `@Environment(\.dismiss)` would:
///
/// ```swift
/// IntentButton(DismissIntent()) {
///     Text("Close")
/// }
/// ```
///
/// Outside a presentation the environment's `dismiss` does nothing, and so does
/// this intent.
public struct DismissIntent: Intent {
    /// Creates an intent that dismisses the current presentation.
    public init() {}

    /// Dismisses the presentation the intent was triggered from.
    @MainActor public func perform(context: Context) async throws {
        context.dismiss()
    }
}
