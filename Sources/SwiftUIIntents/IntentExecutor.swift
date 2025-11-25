//
//  IntentExecutor.swift
//  SwiftUIIntents
//
//  Created by Valeriy Malishevskyi on 29.04.2025.
//

import SwiftUI
import os
import Observation

@MainActor @Observable final class IntentExecutor<PerformResult: Sendable> {
    
    public enum State {
        case idle
        case loading
        case success(PerformResult?)
        case failure(Error)
        
        var value: PerformResult? {
            guard case .success(let value) = self else {
                return nil
            }
            return value
        }
        
        var error: Error? {
            guard case .failure(let error) = self else {
                return nil
            }
            return error
        }
    }
    
    private let signposter = OSSignposter()
    
    private(set) var intent: (any Intent<PerformResult>)?
    private(set) var state: State = .idle
    
    init<I: Intent>(intent: I?) where I.PerformResult == PerformResult {
        self.intent = intent
    }
    
    init(intent: (any Intent<PerformResult>)? = nil) {
        self.intent = intent
    }
    
    func perform(context: IntentContextContainer) async {
        guard let intent = intent else {
            return
        }
        
        let signpostID = signposter.makeSignpostID()
        let signposterState = signposter.beginInterval("Intent Execution", id: signpostID)
        
        state = .loading
        do {
            let result: PerformResult? = try await intent.perform(context: context)
            signposter.emitEvent("Execution complete.", id: signpostID)
            state = .success(result)
        } catch {
            print("Intent execution failed with error: \(error)")
            state = .failure(error)
        }
        signposter.endInterval("Intent Execution", signposterState)
    }
    
    
    func updateIntent(_ intent: (any Intent<PerformResult>)?){
        self.intent = intent
    }
}
