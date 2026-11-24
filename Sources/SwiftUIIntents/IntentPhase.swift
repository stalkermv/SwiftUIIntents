//
//  IntentPhase.swift
//  SwiftUIIntents
//

/// Where an intent run currently is.
///
/// `cancelled` is not `idle`: a cancelled run is not a failure and raises no error,
/// but the UI can still tell "never ran" from "was stopped".
public enum IntentPhase: Sendable, Hashable {
    /// Nothing has run yet.
    case idle
    /// The intent is performing.
    case running
    /// The intent threw an error.
    case failed
    /// The run was cancelled, by the user, by a handle, or because its view went away.
    case cancelled
    /// The intent returned a result.
    case finished
}
