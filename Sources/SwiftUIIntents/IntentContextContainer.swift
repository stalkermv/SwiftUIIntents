//
//  IntentContext.swift
//  SwiftUIIntents
//
//  Created by Valeriy Malishevskyi on 29.04.2025.
//

import SwiftUI

@MainActor @dynamicMemberLookup
public struct IntentContextContainer {
    private let environment: EnvironmentValues
    
    init(environment: EnvironmentValues) {
        self.environment = environment
    }
    
    public subscript<T>(dynamicMember keyPath: KeyPath<EnvironmentValues, T>) -> T {
        environment[keyPath: keyPath]
    }
}
