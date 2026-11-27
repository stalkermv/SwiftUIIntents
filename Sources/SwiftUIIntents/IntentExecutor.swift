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
    private(set) var phase: IntentPhase = .idle
    private(set) var latestErrorEvent: IntentErrorEvent?
    /// The most recent events of this executor's runs, newest last.
    private(set) var events: [IntentEvent] = []
    /// The latest run; an older run that finishes late must not overwrite it.
    private var currentRun = UUID()
    /// The run in flight and how to cancel it. A new run cancels it, because the
    /// new run supersedes it.
    private var inFlight: (run: UUID, cancel: @MainActor () -> Void)?
    /// Identifies this executor's events, so a hook can tell its events apart
    /// from those of another executor.
    private let eventSource = UUID()
    private var eventSequence = 0

    init() {}

    private func emit(
        _ kind: IntentEvent.Kind,
        type: ObjectIdentifier,
        identifier: String
    ) {
        eventSequence += 1
        events.append(IntentEvent(
            source: eventSource,
            sequence: eventSequence,
            intentType: type,
            identifier: identifier,
            kind: kind
        ))
        if events.count > 32 {
            events.removeFirst(events.count - 32)
        }
    }

    /// Runs `intent` in a task of its own and waits for it.
    ///
    /// The run is a separate task so that a handle can cancel exactly this run, and
    /// so that a ``LongRunningIntent`` can be left running when the task that
    /// called this method is cancelled because its view went away.
    ///
    /// A new run supersedes the run still in flight on this executor and cancels
    /// it, a long-running one included: under `cancelAndRestart`, a new
    /// `task(id:)` value or a new `onChange` value the old run is no longer wanted,
    /// even though its view is still there.
    func perform(
        _ intent: any Intent<PerformResult>,
        context: IntentContextContainer,
        handle: (any IntentRunBinding)? = nil
    ) async {
        let signpostID = signposter.makeSignpostID()
        let name: StaticString = "Intent Execution"
        let identifier = intent.identifier
        let type = ObjectIdentifier(Swift.type(of: intent))
        let isLongRunning = intent is any LongRunningIntent
        // The interval *name* must be a StaticString, so the intent cannot be
        // the name. Passing it as the interval's message is what makes separate
        // intents distinguishable in Instruments.
        let signposterState = signposter.beginInterval(
            name,
            id: signpostID,
            "\(identifier, privacy: .public)"
        )
        defer { signposter.endInterval(name, signposterState) }

        let thisRun = UUID()
        currentRun = thisRun
        if let superseded = inFlight {
            inFlight = nil
            superseded.cancel()
        }
        state = .loading
        phase = .running
        latestErrorEvent = nil
        emit(.phase(.running), type: type, identifier: identifier)
        if let reporting = intent as? any ProgressReportingIntent {
            emit(.progress(reporting.progress), type: type, identifier: identifier)
        }

        let box = IntentCancellationBox()
        // The context is installed here, not at the view, so that every caller of
        // this method is covered, including tests, which reach the executor
        // directly. `Task { }` inherits task-local values and the main actor, so
        // `@IntentContext` works inside the intent; `Task.detached` would not.
        let run = Task { @MainActor () throws -> PerformResult in
            try await withIntentContext(context, cancellationBox: box) {
                try await intent.perform(context: context)
            }
        }
        inFlight = (thisRun, {
            box.record(.viewDisappeared)
            run.cancel()
        })
        handle?.bind(run: thisRun) { reason in
            box.record(reason)
            run.cancel()
        }
        let registryID = isLongRunning ? LongRunningIntentRegistry.shared.register(identifier) : nil
        defer {
            // A newer run may have bound the handle and taken the in-flight slot
            // while this one was finishing; leave those alone.
            handle?.unbind(run: thisRun)
            if inFlight?.run == thisRun { inFlight = nil }
            if let registryID { LongRunningIntentRegistry.shared.finish(registryID) }
        }

        do {
            let result = try await withTaskCancellationHandler {
                try await run.value
            } onCancel: {
                // A long-running intent is not cancelled with its view. A run
                // that supersedes it cancels it through `inFlight` instead.
                if !isLongRunning { run.cancel() }
            }
            signposter.emitEvent("Execution complete.", id: signpostID)
            guard currentRun == thisRun else { return }
            state = .success(result)
            phase = .finished
            latestErrorEvent = nil
            emit(.value(result), type: type, identifier: identifier)
            emit(.phase(.finished), type: type, identifier: identifier)
        } catch is CancellationError {
            // Cancellation is routine: the view disappeared, a `.task(id:)` was
            // superseded, or a handle stopped the run. It is not an error.
            intentLogger.debug("Intent \(identifier, privacy: .public) cancelled")
            guard currentRun == thisRun else { return }
            state = .idle
            phase = .cancelled
            latestErrorEvent = nil
            emit(.phase(.cancelled), type: type, identifier: identifier)
        } catch {
            intentLogger.error(
                "Intent \(identifier, privacy: .public) failed: \(error.localizedDescription, privacy: .public)"
            )
            if isLongRunning {
                LongRunningIntentRegistry.shared.logFailure(identifier, error)
            }
            guard currentRun == thisRun else { return }
            state = .failure(error)
            phase = .failed
            let event = IntentErrorEvent(error: error)
            latestErrorEvent = event
            emit(.error(error), type: type, identifier: identifier)
            emit(.phase(.failed), type: type, identifier: identifier)
        }
    }
}
