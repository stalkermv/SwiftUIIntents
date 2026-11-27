//
//  Intent.swift
//  SwiftUIIntents
//
//  Created by Valeriy Malishevskyi on 29.04.2025.
//

import SwiftUI

/// Describes a unit of async work that can be triggered from SwiftUI.
///
/// An intent has one requirement, `perform(context:)`. Return a value when the
/// intent produces one; leave the return out when it only has side effects, and
/// its `PerformResult` is `Void`:
///
/// ```swift
/// struct SaveDraft: Intent {
///     func perform(context: Context) async throws { … }
/// }
///
/// struct LoadDraft: Intent {
///     func perform(context: Context) async throws -> Draft { … }
/// }
/// ```
public protocol Intent<PerformResult>: Sendable {
    typealias Context = IntentContextContainer
    associatedtype PerformResult : Sendable

    /// A stable identifier used for diagnostics, for telling apart intents of the
    /// same type in event hooks, and for intent composition.
    var identifier: String { get }

    /// Performs the intent and returns its result.
    @MainActor func perform(context: Context) async throws -> PerformResult
}

extension Intent {
    /// The default instance identifier derived from the intent type name.
    public var identifier: String { Self.identifier }
    /// The default type identifier derived from the intent type name.
    public static var identifier: String { String(describing: self) }
}

/// A no-op intent that is useful for previews and placeholder flows.
public struct EmptyIntent: Intent {
    /// Creates an empty intent.
    public init() {}
    /// Performs no work.
    public func perform(context: Context) async throws {
        // No action needed for this empty intent
    }
}
