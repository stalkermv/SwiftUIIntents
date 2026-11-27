//
//  IntentTaskOwner.swift
//  SwiftUIIntents
//

import Foundation

/// What a view-owned trigger does when it fires while its previous run is still
/// going.
public enum IntentReentryPolicy: Sendable, Hashable {
    /// Ignore the new trigger until the run in flight finishes.
    case ignore
    /// Cancel the run in flight and start the new one.
    case cancelAndRestart
    /// Start the new run after the one in flight finishes.
    case queue
}

/// Owns the tasks of a trigger that SwiftUI does not own, such as `onSubmit`.
///
/// Every task the owner started and that has not finished yet, including runs
/// waiting in the queue, is cancelled when the owner is released, which happens
/// when the view that holds it in `@State` leaves the hierarchy, and by
/// ``cancel()``. A queued run that is cancelled before its turn never starts.
///
/// A run of a ``LongRunningIntent`` that has already started is not stopped by
/// this: the executor does not pass the cancellation of the view on to it. A new
/// run that replaces it under ``IntentReentryPolicy/cancelAndRestart`` does stop
/// it, because the executor cancels the run it supersedes.
final class IntentTaskOwner: @unchecked Sendable {
    private let lock = NSLock()
    /// Every task that has not finished, in the order they were started.
    private var tasks: [(token: UUID, task: Task<Void, Never>)] = []

    /// Whether a task this owner started is still in flight or queued.
    var isRunning: Bool {
        lock.lock(); defer { lock.unlock() }
        return !tasks.isEmpty
    }

    /// Starts `work` according to `policy`.
    @MainActor
    func start(
        policy: IntentReentryPolicy = .cancelAndRestart,
        _ work: @escaping @MainActor () async -> Void
    ) {
        lock.lock()
        if policy == .ignore, !tasks.isEmpty {
            lock.unlock()
            return
        }
        let previous = policy == .queue ? tasks.last?.task : nil
        if policy == .cancelAndRestart {
            for entry in tasks { entry.task.cancel() }
        }
        let myToken = UUID()
        let task = Task { @MainActor [weak self] in
            if let previous {
                await previous.value
            }
            // A run that was cancelled while it waited never starts.
            if !Task.isCancelled {
                await work()
            }
            self?.finish(myToken)
        }
        tasks.append((myToken, task))
        lock.unlock()
    }

    private func finish(_ finished: UUID) {
        lock.lock(); defer { lock.unlock() }
        tasks.removeAll { $0.token == finished }
    }

    /// Cancels every run in flight and every run waiting in the queue.
    func cancel() {
        lock.lock()
        let current = tasks.map(\.task)
        lock.unlock()
        for task in current { task.cancel() }
    }

    deinit {
        for entry in tasks { entry.task.cancel() }
    }
}
