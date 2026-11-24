//
//  IntentComposition.swift
//  SwiftUIIntents
//

import SwiftUI

extension Intent {
    /// Returns a new intent that executes `self` and then `other`.
    public func combined<T: Intent>(with other: T) -> CombinedIntent<Self, T> {
        CombinedIntent(self, other)
    }
    
    /// Returns a new intent that executes `self` and `other` concurrently.
    public func combined<T: Intent>(simultaneously other: T) -> SimultaneousCombinedIntent<Self, T> {
        SimultaneousCombinedIntent(self, other)
    }
}

/// An intent that runs two intents concurrently and returns both results.
public struct SimultaneousCombinedIntent<I1: Intent, I2: Intent>: Intent {
    
    public typealias PerformResult = (I1.PerformResult, I2.PerformResult)
    
    let first: I1
    let second: I2
    
    init(_ first: I1, _ second: I2) {
        self.first = first
        self.second = second
    }
 
    /// Executes both wrapped intents concurrently.
    public func perform(context: Context) async throws -> PerformResult {
        async let firstResult: I1.PerformResult = try await first.perform(context: context)
        async let secondResult: I2.PerformResult = try await second.perform(context: context)
        
        return (try await firstResult, try await secondResult)
    }
}

/// An intent that runs two intents sequentially and returns both results.
public struct CombinedIntent<I1: Intent, I2: Intent>: Intent {
    
    public typealias PerformResult = (I1.PerformResult, I2.PerformResult)
    
    let first: I1
    let second: I2
    
    init(_ first: I1, _ second: I2) {
        self.first = first
        self.second = second
    }
 
    /// Executes the wrapped intents in order.
    public func perform(context: Context) async throws -> PerformResult {
        let firstResult: I1.PerformResult = try await first.perform(context: context)
        let secondResult: I2.PerformResult = try await second.perform(context: context)
        return (firstResult, secondResult)
    }
}
