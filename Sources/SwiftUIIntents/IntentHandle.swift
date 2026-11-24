//
//  IntentHandle.swift
//  SwiftUIIntents
//

import SwiftUI

/// Cancels the run of an intent that a trigger started.
///
/// Create the handle in view state and pass it to exactly one trigger:
///
/// ```swift
/// @State private var upload = IntentHandle<UploadIntent>()
///
/// IntentButton(handle: upload, UploadIntent(file: file)) { Text("Upload") }
/// Button("Cancel") { upload.cancel() }
/// ```
///
/// The handle binds when a run starts, not when the trigger appears. Before a run
/// there is nothing to cancel, so ``cancel()`` does nothing. A run of a
/// ``LongRunningIntent`` stays cancellable after the trigger's view has gone,
/// because the handle holds the run, not the view.
@MainActor
public final class IntentHandle<I: Intent> {
    private var cancelRun: (@MainActor (IntentCancellationReason) -> Void)?

    /// Creates a handle that is not bound to a run.
    public init() {}

    /// Cancels the run in flight, if there is one.
    public func cancel() {
        cancelRun?(.userCancelled)
    }

    func bind(_ cancel: @escaping @MainActor (IntentCancellationReason) -> Void) {
        cancelRun = cancel
    }

    func unbind() {
        cancelRun = nil
    }
}

/// What the executor needs from a handle, without the intent type.
@MainActor
protocol IntentRunBinding: AnyObject {
    func bind(_ cancel: @escaping @MainActor (IntentCancellationReason) -> Void)
    func unbind()
}

extension IntentHandle: IntentRunBinding {}
