//
//  IntentMarkers.swift
//  SwiftUIIntents
//

import Foundation
internal import ServiceContextModule

/// Why a run was cancelled.
public enum IntentCancellationReason: Sendable, Hashable {
    /// A handle's `cancel()` was called.
    case userCancelled
    /// SwiftUI cancelled the run because its view went away or was superseded.
    case viewDisappeared
}

/// An intent that wants to clean up when its run is cancelled.
public protocol CancellableIntent: Intent {}

extension CancellableIntent {
    /// Runs `operation` and calls `onCancel` if the run is cancelled while it is
    /// in progress, with the reason.
    ///
    /// Call it from `perform(context:)`. The reason is read from the run's
    /// context when the call starts, because the cancellation handler runs on
    /// whichever thread asked for the cancellation, outside the run's task-local
    /// values.
    public func withIntentCancellationHandler<T>(
        operation: () async throws -> T,
        onCancel: @escaping @Sendable (IntentCancellationReason) -> Void
    ) async rethrows -> T {
        let box = ServiceContext.current?[IntentCancellationBoxKey.self]
        return try await withTaskCancellationHandler {
            try await operation()
        } onCancel: {
            onCancel(box?.reason ?? .viewDisappeared)
        }
    }
}

/// An intent that reports its progress.
///
/// Store the `Progress` in the intent so every access returns the same object:
///
/// ```swift
/// struct Upload: ProgressReportingIntent {
///     let progress = Progress(totalUnitCount: 100)
///     func perform(context: Context) async throws { … progress.completedUnitCount = 40 … }
/// }
/// ```
public protocol ProgressReportingIntent: Intent {
    /// The progress the run updates.
    var progress: Progress { get }
}

/// An intent whose work must finish even if the view that started it goes away.
///
/// A run of a long-running intent is not cancelled when its view disappears.
/// It runs in an app-scoped registry until it finishes, and ``IntentHandle/cancel()``
/// can still stop it.
///
/// - Important: After the view is gone, no `onChangeIntent…` or `onReceiveIntent…`
///   hook fires for the run, because those hooks need a mounted view. The marker
///   guarantees that the work finishes, not that a screen hears about it. A failure
///   after the view is gone is written to the log. The run lives only as long as the
///   process; it does not request background execution time.
public protocol LongRunningIntent: Intent {}

/// A reference that records why a run was cancelled, before the cancel call.
final class IntentCancellationBox: @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: IntentCancellationReason?

    var reason: IntentCancellationReason? {
        lock.lock(); defer { lock.unlock() }
        return recorded
    }

    func record(_ reason: IntentCancellationReason) {
        lock.lock(); defer { lock.unlock() }
        if recorded == nil { recorded = reason }
    }
}

struct IntentCancellationBoxKey: ServiceContextKey {
    typealias Value = IntentCancellationBox
}
