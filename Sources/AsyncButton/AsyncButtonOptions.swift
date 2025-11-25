//
//  AsyncButtonOptions.swift
//  CustomComponents
//
//  Created by Valeriy Malishevskyi on 13.05.2025.
//

import SwiftUI

/// Options to configure the behavior of `AsyncButton`.
/// Use these options to **disable** or **hide** features.
/// The default (empty set) enables all features except keeping the button enabled during execution.
public struct AsyncButtonOptions: OptionSet, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    /// Hide the loading indicator during the async operation.
    public static let loadingIndicatorHidden = AsyncButtonOptions(rawValue: 1 << 0)
    /// Keep the button enabled while the async operation is running (default is disabled).
    public static let enabledDuringExecution = AsyncButtonOptions(rawValue: 1 << 1)
    /// Detach the task from the button's lifecycle (won't be cancelled on deinit).
    public static let detachesTask = AsyncButtonOptions(rawValue: 1 << 2)
}
