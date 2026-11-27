//
//  LongRunningIntentRegistry.swift
//  SwiftUIIntents
//

import Foundation
import os

private let registryLogger = Logger(
    subsystem: "com.stalkermv.SwiftUIIntents",
    category: "LongRunningIntent"
)

/// Keeps the runs of ``LongRunningIntent`` intents until they finish.
///
/// Runs are unstructured tasks, not detached ones: an unstructured task inherits
/// task-local values, so `@IntentContext` still works inside the intent, and it
/// is not cancelled when the view that started it goes away.
@MainActor
final class LongRunningIntentRegistry {
    static let shared = LongRunningIntentRegistry()

    private var running: [UUID: String] = [:]

    var activeIdentifiers: [String] {
        Array(running.values)
    }

    func register(_ identifier: String) -> UUID {
        let id = UUID()
        running[id] = identifier
        return id
    }

    func finish(_ id: UUID) {
        running[id] = nil
    }

    func logFailure(_ identifier: String, _ error: Error) {
        registryLogger.error(
            "Long-running intent \(identifier, privacy: .public) failed: \(error.localizedDescription, privacy: .public)"
        )
    }
}
