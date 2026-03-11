//
//  IntentContext.swift
//  SwiftUIIntents
//
//  Created by Valeriy Malishevskyi on 26.11.2025.
//

import SwiftUI
internal import ServiceContextModule

/// Reads the current intent execution context from `ServiceContext`.
@propertyWrapper
public struct IntentContext: Sendable {
    /// The SwiftUI environment snapshot captured when the intent started running.
    public var wrappedValue: SwiftUIIntents.IntentContextContainer {
        get {
            guard let context = ServiceContext.current?[IntentContextKey.self] else {
                fatalError("Reading IntentContext outside of Intent execution context is not allowed")
            }
            return context
        }
    }
    
    /// Creates a context reader for use inside an intent implementation.
    public init() {}
}
