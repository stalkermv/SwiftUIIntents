//
//  Intent.swift
//  SwiftUIIntents
//
//  Created by Valeriy Malishevskyi on 29.04.2025.
//

import SwiftUI

/// Describes a unit of async work that can be triggered from SwiftUI.
public protocol Intent<PerformResult>: Sendable {
    typealias Context = IntentContextContainer
    associatedtype PerformResult : Sendable
    
    /// A stable identifier used for diagnostics and intent composition.
    var identifier: String { get }
    
    /// Performs the intent without returning a value.
    @MainActor func perform(context: Context) async throws
    /// Performs the intent and returns a typed result.
    @MainActor func perform(context: Context) async throws -> Self.PerformResult
}

extension Intent {
    /// The default instance identifier derived from the intent type name.
    public var identifier: String { Self.identifier }
    /// The default type identifier derived from the intent type name.
    public static var identifier: String { String(describing: self) }
}

extension Intent {
    /// Default no-value implementation for intents that only implement the valued variant.
    public func perform(context: Context) async throws {
        assertionFailure("perform(context:) not implemented")
    }
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
