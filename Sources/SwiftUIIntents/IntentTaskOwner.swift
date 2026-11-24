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

/// Owns the task of a trigger that SwiftUI does not own, such as `onSubmit`.
///
/// The task is cancelled when the owner is released, which happens when the view
/// that holds it in `@State` leaves the hierarchy, and by ``cancel()``. A run of a
/// ``LongRunningIntent`` is not affected by this: the executor does not pass the
/// cancellation on to it.
final class IntentTaskOwner: @unchecked Sendable {
    private let lock = NSLock()
    private var task: Task<Void, Never>?
    private var token = UUID()
    private var isRunning = false

    /// Starts `work` according to `policy`.
    @MainActor
    func start(
        policy: IntentReentryPolicy = .cancelAndRestart,
        _ work: @escaping @MainActor () async -> Void
    ) {
        lock.lock()
        if policy == .ignore, isRunning {
            lock.unlock()
            return
        }
        let previous = policy == .queue ? task : nil
        if policy == .cancelAndRestart {
            task?.cancel()
        }
        let myToken = UUID()
        token = myToken
        isRunning = true
        task = Task { @MainActor [weak self] in
            if let previous {
                await previous.value
            }
            await work()
            self?.finish(myToken)
        }
        lock.unlock()
    }

    private func finish(_ finished: UUID) {
        lock.lock(); defer { lock.unlock() }
        if token == finished {
            isRunning = false
            task = nil
        }
    }

    /// Cancels the run in flight.
    func cancel() {
        lock.lock()
        let current = task
        lock.unlock()
        current?.cancel()
    }

    deinit {
        task?.cancel()
    }
}
