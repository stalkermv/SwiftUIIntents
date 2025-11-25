//
//  IntentContext.swift
//  SwiftUIIntents
//
//  Created by Valeriy Malishevskyi on 26.11.2025.
//

import SwiftUI
internal import ServiceContextModule

@propertyWrapper
public struct IntentContext {
    public var wrappedValue: SwiftUIIntents.IntentContextContainer {
        get {
            guard let context = ServiceContext.current?[IntentContextKey.self] else {
                fatalError("Reading IntentContext outside of Intent execution context is not allowed")
            }
            return context
        }
    }
    
    public init() {}
}
