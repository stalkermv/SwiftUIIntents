//
//  Intent.swift
//  SwiftUIIntents
//
//  Created by Valeriy Malishevskyi on 29.04.2025.
//

import SwiftUI

public protocol Intent<PerformResult>: Sendable {
    typealias Context = IntentContextContainer
    associatedtype PerformResult : Sendable
    
    var identifier: String { get }
    
    @MainActor func perform(context: Context) async throws
    @MainActor func perform(context: Context) async throws -> Self.PerformResult
}

extension Intent {
    public var identifier: String { Self.identifier }
    public static var identifier: String { String(describing: self) }
}

extension Intent {
    public func perform(context: Context) async throws {
        assertionFailure("perform(context:) not implemented")
    }
}

public struct EmptyIntent: Intent {
    public init() {}
    public func perform(context: Context) async throws {
        // No action needed for this empty intent
    }
}
