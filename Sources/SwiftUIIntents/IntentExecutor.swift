//
//  IntentExecutor.swift
//  SwiftUIIntents
//
//  Created by Valeriy Malishevskyi on 29.04.2025.
//

import SwiftUI
import os
import Observation

private let intentLogger = Logger(
    subsystem: "com.stalkermv.SwiftUIIntents",
    category: "IntentExecution"
)

@MainActor @Observable final class IntentExecutor<PerformResult: Sendable> {
    
    /// Describes the latest execution state for an intent.
    public enum State {
        /// The intent has not started yet, or the run that was in flight was
        /// cancelled before it produced a result. Cancellation is routine — a
        /// view disappearing, or a `.task(id:)` superseded — so it returns the
        /// executor to this state rather than reporting a failure.
        case idle
        /// The intent is currently executing.
        case loading
        /// The intent finished successfully with an optional result value.
        case success(PerformResult?)
        /// The intent failed with an error.
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
    
    private(set) var state: State = .idle
    private(set) var latestErrorEvent: IntentErrorEvent?

    init() {}

    func perform(_ intent: any Intent<PerformResult>, context: IntentContextContainer) async {
        let signpostID = signposter.makeSignpostID()
        let name: StaticString = "Intent Execution"
        // The interval *name* must be a StaticString, so the intent cannot be
        // the name. Passing it as the interval's message is what makes separate
        // intents distinguishable in Instruments.
        let signposterState = signposter.beginInterval(
            name,
            id: signpostID,
            "\(intent.identifier, privacy: .public)"
        )
        defer { signposter.endInterval(name, signposterState) }

        state = .loading
        latestErrorEvent = nil

        do {
            // The context is installed here, not at the binding, so that every
            // caller of this method is covered — including tests, which reach the
            // executor directly.
            let result: PerformResult? = try await withIntentContext(context) {
                try await intent.perform(context: context)
            }
            signposter.emitEvent("Execution complete.", id: signpostID)
            state = .success(result)
            latestErrorEvent = nil
        } catch is CancellationError {
            // Cancellation is routine: the view disappeared, or a .task(id:)
            // was superseded. It is not something to show the user.
            intentLogger.debug("Intent \(intent.identifier, privacy: .public) cancelled")
            state = .idle
            latestErrorEvent = nil
        } catch {
            intentLogger.error(
                "Intent \(intent.identifier, privacy: .public) failed: \(error.localizedDescription, privacy: .public)"
            )
            state = .failure(error)
            latestErrorEvent = IntentErrorEvent(error: error)
        }
    }
}
