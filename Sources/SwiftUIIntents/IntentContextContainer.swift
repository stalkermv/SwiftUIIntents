//
//  IntentContext.swift
//  SwiftUIIntents
//
//  Created by Valeriy Malishevskyi on 29.04.2025.
//

import SwiftUI

/// Provides read-only access to the SwiftUI environment for a running intent.
@MainActor @dynamicMemberLookup
public struct IntentContextContainer {
    private let environment: EnvironmentValues
    
    init(environment: EnvironmentValues) {
        self.environment = environment
    }
    
    /// Reads a value from the captured SwiftUI environment.
    public subscript<T>(dynamicMember keyPath: KeyPath<EnvironmentValues, T>) -> T {
        environment[keyPath: keyPath]
    }
}
